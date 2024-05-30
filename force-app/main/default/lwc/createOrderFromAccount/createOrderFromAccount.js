import { LightningElement, wire, track, api } from 'lwc';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import { NavigationMixin } from 'lightning/navigation';
import { CloseActionScreenEvent } from "lightning/actions";

import getProducts from '@salesforce/apex/OrderController.getProducts';
import createOrder from '@salesforce/apex/OrderController.createOrder';
import createOrderItems from '@salesforce/apex/OrderController.createOrderItems';

export default class CreateOrderFromAccount extends NavigationMixin(LightningElement) {
    @api recordId;
    @track products;
    @track productOptions = [];
    @track selectedValues= [];

    @wire(getProducts)
    wiredProducts({ error, data }) {
        if (data) {
            this.products = data;
            this.products.forEach(product => {
              const label = `${product.productName} - R$ ${product.unitPrice}`;
              this.productOptions.push({ label: label, value: product.productId, family: product.family })}
            )
        } else if (error) {
            this.showToast('Erro! Os produtos não foram recuperados.', error.body.message, 'error');
        }
    }

    handleProductChange(event) {
      const selectedOptions = event.detail.value;
      const tempFamilyMap = new Map();

      for (let value of selectedOptions) {
        const product = this.productOptions.find(option => option.value === value);
        if (product) {
          const family = product.family;
            if (tempFamilyMap.has(family)) {
                this.showToast('Erro!', `Só é possível selecionar um produto da família ${family}.`, 'error');
                this.selectedValues = this.selectedValues.filter(val => val !== value);
                return;
            }
            tempFamilyMap.set(family, value);
        }
      }
          this.selectedValues = selectedOptions;
    }


    getDisabledOptions() {
      const disabledOptions = new Set();
  
      for (let selectedValue of this.selectedValues) {
          const selectedProduct = this.productOptions.find(option => option.value === selectedValue);
          if (selectedProduct) {
              const family = selectedProduct.family;
              this.productOptions.forEach(option => {
                  if (option.family === family && option.value !== selectedValue) {
                      disabledOptions.add(option.value);
                  }
              });
          }
      }
  
      return Array.from(disabledOptions);
  }

  handleCreateOrder() {
    const accountId = this.recordId;
    const selectedProductsJSON = this.selectedValues.map(value => {
      const product = this.products.find(p => p.productId === value);
      return JSON.stringify({ productId: product.productId, unitPrice: product.unitPrice.toString() });
  });

      createOrder({ accountId })
          .then(order => {
            createOrderItems({ order: order, selectedProducts: selectedProductsJSON })
                    .then(() => {
                        this.showToast('Sucesso!', 'Pedido criado com sucesso!', 'success');
                        this.navigateToRecord(order.Id);
                        this.closeModal();
                    })
                    .catch(error => {
                        console.error('Erro ao criar itens do pedido: ' + JSON.stringify(error));
                    });
          })
          .catch(error => {
              this.showToast('Erro! O pedido não foi criado.', error.body.message, 'error');
          });
}

    closeModal(){
      this.dispatchEvent(new CloseActionScreenEvent());
    }

    handleCancel(){
      this.closeModal();
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({ title, message, variant });
        this.dispatchEvent(evt);
    }

    navigateToRecord(recordId) {
        this[NavigationMixin.Navigate]({
            type: 'standard__recordPage',
            attributes: {
                recordId: recordId,
                objectApiName: 'Order',
                actionName: 'view'
            }
        });
    }
}

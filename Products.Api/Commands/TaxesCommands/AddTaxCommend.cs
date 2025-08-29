using Azure.Core;
using MediatR;
using Products.Api.Domain;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Commands.TaxesCommands
{
    public class AddTaxQuery : IRequest<bool>
    {
        public CreateTaxRequestDto Request { get; }
        public AddTaxQuery(CreateTaxRequestDto request)
        {
            Request = request;
        }
        public class AddTaxQueryHandler : IRequestHandler<AddTaxQuery, bool>
        {
            private readonly TaxRepository _taxRepository;
            public AddTaxQueryHandler(TaxRepository taxRepository)
            {
                _taxRepository = taxRepository;
            }
            public async Task<bool> Handle(AddTaxQuery request, CancellationToken cancellationToken)
            {
                var tax = Tax.Create(
                    request.Request.Name,
                    request.Request.Rate,
                    request.Request.Code,
                    request.Request.IsFixed,
                    request.Request.IsTaxOnTotal,
                    request.Request.IsEnabled
                );
                // Check if a tax with the same name already exists
                var existingTaxes = await _taxRepository.GetAllTaxesAsync();
                if (existingTaxes.Any(t => t.Name.Equals(tax.Name, StringComparison.OrdinalIgnoreCase)))
                {
                    throw new InvalidOperationException($"A tax with the name '{tax.Name}' already exists.");
                }
                // Add the new tax
                await _taxRepository.AddTaxAsync(tax);

                return true;
            }
        }
    }
}

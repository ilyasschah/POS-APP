using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.CustomerDiscountCommands
{
    public class CreateCustomerDiscountCommand : IRequest<CustomerDiscountDto>
    {
        public int CompanyId { get; set; }
        public CreateCustomerDiscountRequest Request { get; set; }

        public CreateCustomerDiscountCommand(int companyId, CreateCustomerDiscountRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class CreateCustomerDiscountCommandHandler : IRequestHandler<CreateCustomerDiscountCommand, CustomerDiscountDto>
        {
            private readonly CustomerDiscountService _service;
            public CreateCustomerDiscountCommandHandler(CustomerDiscountService service) => _service = service;

            public async Task<CustomerDiscountDto> Handle(CreateCustomerDiscountCommand command, CancellationToken cancellationToken)
            {
                var entity = await _service.Create(command.CompanyId, command.Request);
                return new CustomerDiscountDto { Id = entity.Id, CompanyId = entity.CompanyId, CustomerId = entity.CustomerId, Type = entity.Type, Uid = entity.Uid, Value = entity.Value };
            }
        }
    }
}
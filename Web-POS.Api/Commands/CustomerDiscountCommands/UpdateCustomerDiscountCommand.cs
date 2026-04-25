using MediatR;
using Api.Models;
using Api.Services;

namespace Api.Commands.CustomerDiscountCommands
{
    public class UpdateCustomerDiscountCommand : IRequest<bool>
    {
        public int CompanyId { get; set; }
        public UpdateCustomerDiscountRequest Request { get; set; }

        public UpdateCustomerDiscountCommand(int companyId, UpdateCustomerDiscountRequest request)
        {
            CompanyId = companyId;
            Request = request;
        }

        public class UpdateCustomerDiscountCommandHandler : IRequestHandler<UpdateCustomerDiscountCommand, bool>
        {
            private readonly CustomerDiscountService _service;
            public UpdateCustomerDiscountCommandHandler(CustomerDiscountService service) => _service = service;

            public async Task<bool> Handle(UpdateCustomerDiscountCommand command, CancellationToken cancellationToken)
            {
                return await _service.Update(command.CompanyId, command.Request);
            }
        }
    }
}
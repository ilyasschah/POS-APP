using MediatR;
using Api.Services;

namespace Api.Commands.CustomerDiscountCommands
{
    public class DeleteCustomerDiscountCommand : IRequest<bool>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public DeleteCustomerDiscountCommand(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class DeleteCustomerDiscountCommandHandler : IRequestHandler<DeleteCustomerDiscountCommand, bool>
        {
            private readonly CustomerDiscountService _service;
            public DeleteCustomerDiscountCommandHandler(CustomerDiscountService service) => _service = service;

            public async Task<bool> Handle(DeleteCustomerDiscountCommand command, CancellationToken cancellationToken)
            {
                return await _service.Delete(command.Id, command.CompanyId);
            }
        }
    }
}
//using Products.Api.Services;
//using MediatR;

//namespace Products.Api.Commands.ApplicationPropertyCommands.Delete
//{
//    public class DeleteApplicationPropertyCommand : IRequest<bool>
//    {
//        public string Name { get; }
//        public int CompanyId { get; set; }

//        public DeleteApplicationPropertyCommand(string name, int companyId)
//        {
//            Name = name;
//            CompanyId = companyId;
//        }

//        public class DeleteApplicationPropertyCommandHandler
//            : IRequestHandler<DeleteApplicationPropertyCommand, bool>
//        {
//            private readonly ApplicationPropertyService _service;

//            public DeleteApplicationPropertyCommandHandler(ApplicationPropertyService service)
//            {
//                _service = service;
//            }

//            public Task<bool> Handle(DeleteApplicationPropertyCommand command, CancellationToken cancellationToken)
//            {
//                return _service.Delete(command.Name, command.CompanyId);
//            }
//        }
//    }
//}
